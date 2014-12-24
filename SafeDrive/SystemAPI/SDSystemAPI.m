
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDSystemAPI.h"
#import "NSBundle+LoginItem.h"

@import AppKit;
@import DiskArbitration; // May be necessary if higher level APIs don't work out


@interface SDSystemAPI ()

@end

@implementation SDSystemAPI

- (instancetype)init {
    self = [super init];
    if (self) {
        //
    }
    return self;
}

- (void)dealloc {
    //never
}


#pragma mark
#pragma mark Public API

+(SDSystemAPI *)sharedAPI {
    static SDSystemAPI *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDSystemAPI alloc] init];
    });
    return localInstance;
}

-(NSDictionary *)statusForMountpoint:(NSURL *)mountpointURL {
    NSMutableDictionary *mountpointInfo = [NSMutableDictionary new];
    NSError *error;
    NSNumber *volumeSize;
    if([mountpointURL getResourceValue:&volumeSize forKey:NSURLVolumeTotalCapacityKey error:&error]) {
        NSLog(@"Volume size in bytes: %@", volumeSize);
        mountpointInfo[NSURLVolumeTotalCapacityKey] = volumeSize;
    }
    else {
        /* Handle error */
    }
    NSNumber *volumeSpaceAvailable;
    if([mountpointURL getResourceValue:&volumeSpaceAvailable forKey:NSURLVolumeAvailableCapacityKey error:&error]) {
        NSLog(@"Volume space available in bytes: %@", volumeSpaceAvailable);
        mountpointInfo[NSURLVolumeAvailableCapacityKey] = volumeSpaceAvailable;
    }
    else {
        /* Handle error */
    }
    return mountpointInfo;
}




-(void)checkForMountedVolume:(NSURL *)mountpointURL withTimeout:(NSTimeInterval)timeout success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock {
    NSOperationQueue *opQueue = [[NSOperationQueue alloc] init];
    [opQueue addOperationWithBlock:^{
        for (NSInteger remainingTime = timeout; remainingTime > 0; remainingTime--) {
            NSArray *mountedVolumes = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeNameKey] options:NSVolumeEnumerationSkipHiddenVolumes];
            for (NSURL *mountedVolumeURL in mountedVolumes) {
                if ([mountedVolumeURL.path isEqualToString:mountpointURL.path]) {
                    successBlock();
                    return;
                }
            }
            [NSThread sleepForTimeInterval:1];
        }
        NSError *volumeError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorTimeout userInfo:@{@"error": @"Volume mount timeout"}];
        failureBlock(volumeError);
    }];
}




-(void)ejectMountpoint:(NSURL *)mountpointURL success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock {
    NSError *error;
    BOOL ejectSuccess = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:mountpointURL error:&error];
    if (ejectSuccess && successBlock) successBlock();
    else {
        failureBlock(error);
    }
}


-(void)registerStartAtLogin:(id)sender success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure {
    [[NSBundle mainBundle] addToLoginItems];
    if ([[NSBundle mainBundle] isLoginItem]) {
        success();
    }
    else {
        NSError *loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorAddLoginItemFailed userInfo:@{@"error": @"Adding login item failed"}];
        failure(loginItemError);
    }
}

-(void)unregisterStartAtLogin:(id)sender success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure {
    [[NSBundle mainBundle] removeFromLoginItems];
    if ([[NSBundle mainBundle] isLoginItem]) {
        NSError *loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveLoginItemFailed userInfo:@{@"error": @"Removing login item failed"}];
        failure(loginItemError);
    }
    else {
        success();
    }
}


@end
