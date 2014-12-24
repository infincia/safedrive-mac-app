
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

- (void)test_SDMountController_mountVolumeWithName {
    XCTAssertNotNil(self.sharedMountController);

    // As this is only used for testing, we can use NSURLComponents which isn't available in OS X 10.8
    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.user = SDTestCredentialsUser;
    urlComponents.password = SDTestCredentialsPassword;
    urlComponents.host = SDTestCredentialsHost;
    urlComponents.path = SDTestCredentialsPath;
    urlComponents.port = @(SDTestCredentialsPort);

    NSURL *url = urlComponents.URL;
    NSLog(@"URL: %@", url);

    [self.sharedMountController mountVolumeWithName:@"SafeDrive" atURL:url success:^{
        XCTAssert(YES, @"Pass");
    } failure:^(NSError *mountError) {
        XCTFail(@"%@", [mountError localizedDescription]);
    }];
}

- (void)test_SDSystemAPI_statusForMountpoint {
    XCTAssertNotNil(self.sharedSystemAPI);
    // test root since it should always work as a URL
    NSDictionary *mountStatus = [self.sharedSystemAPI statusForMountpoint:[NSURL fileURLWithFileSystemRepresentation:"/\0" isDirectory:YES relativeToURL:nil]];
    XCTAssertNotNil(mountStatus);
    XCTAssertTrue(mountStatus[NSURLVolumeTotalCapacityKey]);
    XCTAssertTrue(mountStatus[NSURLVolumeAvailableCapacityKey]);
    NSLog(@"test_SDSystemAPI_statusForMountpoint: %@", mountStatus);
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
