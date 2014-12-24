//
//  main.m
//  shelltest
//
//  Created by steve on 12/11/14.
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDAPI.h"
#import "SDMountController.h"
#import "SDSystemAPI.h"
#import "SDTestCredentials.h"

#define TEST_MODE


int main(int argc, const char * argv[]) {
    @autoreleasepool {

        NSRunLoop *mainRunLoop = [NSRunLoop currentRunLoop];

        SDMountController *sharedMountController = [SDMountController sharedAPI];
        SDAPI *sharedSafedriveAPI = [SDAPI sharedAPI];
        SDSystemAPI *sharedSystemAPI = [SDSystemAPI sharedAPI];

        // As this is only used for testing, we can use NSURLComponents which isn't available in OS X 10.8
        NSURLComponents *urlComponents = [NSURLComponents new];
        urlComponents.user      = SDTestCredentialsUser;
        urlComponents.password  = SDTestCredentialsPassword;
        urlComponents.host      = SDTestCredentialsHost;
        urlComponents.path      = SDTestCredentialsPath;
        urlComponents.port      = @(SDTestCredentialsPort);

        NSURL *url = urlComponents.URL;
        
        [sharedMountController mountVolumeWithName:@"SafeDrive" atURL:url success:^{
            NSLog(@"Shell test successfully mounted SSHFS volume");
        } failure:^(NSError *mountError) {
            NSLog(@"Shell test DID NOT mount SSHFS volume!!! failure code: %@", mountError.userInfo[@"error"]);
            exit((int)mountError.code);
        }];
        [mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:20]];
        [sharedMountController unmountVolumeWithName:@"SafeDrive" success:^{
            NSLog(@"Shell test successfully unmounted SSHFS volume");
        } failure:^(NSError *mountError) {
            NSLog(@"Shell test DID NOT unmount SSHFS volume!!!");
        }];
    }
    return 0;
}
